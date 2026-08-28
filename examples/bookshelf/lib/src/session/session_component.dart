import 'package:bookshelf_api/bookshelf_api.dart';
import 'package:bookshelf_core/bookshelf_core.dart';
import 'package:inject_annotation/inject_annotation.dart';

import 'book_repository.dart';
import 'home_page.dart';

/// Session-scoped module: [BookRepository] is built fresh for every session —
/// it exists nowhere in the root graph. The [Credentials] it consumes are not
/// provided by this module at all: they enter the graph as the value
/// parameter of [SessionComponentFactory.create], and inject here like any
/// other binding.
@module
class SessionModule {
  @provides
  @singleton
  BookRepository provideBookRepository(BooksApi api, Credentials credentials, Logger logger) =>
      BookRepository(api, credentials, logger);
}

/// The session graph: created on login, dropped on logout.
///
/// Everything it exposes — [Credentials], [BookRepository], and the
/// [HomePageFactory] entry point — lives only as long as this instance
/// does. `MainComponent` cannot see any of it directly; the only way in is
/// [SessionComponentFactory], declared below.
///
/// [bookRepository] exists purely so tests can verify the session observes
/// the right backend without pumping a full widget tree — see
/// `test/session_seam_test.dart`.
@Subcomponent([SessionModule])
abstract class SessionComponent {
  HomePageFactory get homePageFactory;

  BookRepository get bookRepository;
}

/// Explicit factory for [SessionComponent]: we declare the shape, the
/// generator supplies the implementation.
///
/// The [Credentials] parameter of [create] is a **value parameter** — the
/// instance passed at the call site becomes an instance binding in the
/// session graph, injectable by anything declared inside it (here:
/// [SessionModule.provideBookRepository]). Declaring this class replaces the
/// factory the generator would otherwise synthesize, which is also why this
/// file needs no `part '….factory.dart';` directive. It must live in the
/// same library as the subcomponent it creates.
///
/// Contrast this with the module-constructor channel used at the root
/// (`ApiModule(baseUrl)`): a module constructor carries *configuration*,
/// fixed once when the graph is built — a factory value parameter carries a
/// *runtime value*, different for every session created.
@subcomponentFactory
abstract class SessionComponentFactory {
  SessionComponent create(Credentials credentials);
}
