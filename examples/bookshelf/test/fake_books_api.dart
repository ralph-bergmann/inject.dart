import 'package:bookshelf_api/bookshelf_api.dart';
import 'package:bookshelf_core/bookshelf_core.dart';
import 'package:inject_annotation/inject_annotation.dart';

/// Deterministic in-memory replacement for [BooksApi] — no
/// `Future.delayed`, so tests run instantly and never touch a clock.
class FakeBooksApi implements BooksApi {
  @override
  String get baseUrl => 'fake://bookshelf';

  static const _passwords = {'alice': 'hunter2'};

  /// Validates against the same canned credential [BooksApi] would accept
  /// in production — a wrong password still throws, so tests can exercise
  /// the login-failure path against this fake, exactly like the real class.
  @override
  Future<String> authenticate(String username, String password) async {
    if (_passwords[username] != password) {
      throw StateError('invalid credentials for $username');
    }
    return 'fake-token-$username';
  }

  @override
  Future<List<Book>> fetchBooks(String token) async => const [
    Book(title: 'Fake Book One', author: 'Test Author'),
    Book(title: 'Fake Book Two', author: 'Test Author'),
  ];
}

/// Has a default constructor — unlike [ApiModule], no runtime config is
/// needed, so `TestComponent.create()` never requires an argument for it.
@module
class FakeApiModule {
  @provides
  @singleton
  BooksApi provideApi() => FakeBooksApi();
}
