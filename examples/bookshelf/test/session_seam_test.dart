import 'package:bookshelf/src/session/session_component.dart';
import 'package:bookshelf_core/bookshelf_core.dart';
import 'package:test/test.dart';

import 'test_component.dart';

void main() {
  group('session subcomponent — test-parent seam', () {
    const credentials = Credentials(username: 'alice', token: 'fake-token-alice');

    test('BookRepository resolved under a session observes the fake API', () async {
      final component = TestComponent.create();

      final SessionComponent session = component.sessionFactory.create(credentials);
      final List<Book> books = await session.bookRepository.loadBooks();

      expect(books, isNotEmpty);
      expect(books.every((book) => book.author == 'Test Author'), isTrue);
    });

    test('each login creates its own fresh BookRepository singleton', () {
      final component = TestComponent.create();

      final SessionComponent sessionA = component.sessionFactory.create(credentials);
      final SessionComponent sessionB = component.sessionFactory.create(credentials);

      expect(identical(sessionA.bookRepository, sessionB.bookRepository), isFalse);
      // Within one session, the same repository is shared everywhere.
      expect(identical(sessionA.bookRepository, sessionA.bookRepository), isTrue);
    });
  });
}
