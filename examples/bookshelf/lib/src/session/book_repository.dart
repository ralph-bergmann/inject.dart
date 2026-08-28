import 'package:bookshelf_api/bookshelf_api.dart';
import 'package:bookshelf_core/bookshelf_core.dart';

/// Loads the signed-in user's books.
///
/// Session-private: nothing outside the session graph can inject it —
/// `SessionModule.provideBookRepository` is the only place that constructs
/// it, and `BooksViewModel` (also session-scoped) is its only consumer.
class BookRepository {
  BookRepository(this._api, this._credentials, this._logger);

  final BooksApi _api;
  final Credentials _credentials;
  final Logger _logger;

  Future<List<Book>> loadBooks() {
    _logger.log('loading books for ${_credentials.username}');
    return _api.fetchBooks(_credentials.token);
  }
}
