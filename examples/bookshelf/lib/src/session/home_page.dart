import 'package:bookshelf_core/bookshelf_core.dart';
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:inject_flutter/inject_flutter.dart';

import 'book_repository.dart';

part 'home_page.factory.dart';

/// Loads and holds the signed-in user's books.
///
/// Session-scoped: [ViewModelFactory] creates a fresh instance whenever
/// [HomePage] is built, and its [BookRepository] dependency is itself
/// session-private — neither type exists outside the `SessionComponent`
/// that produced this ViewModel.
@inject
class BooksViewModel extends ChangeNotifier {
  BooksViewModel({required this._repository});

  final BookRepository _repository;

  List<Book> _books = const [];
  bool _loading = true;
  String? _error;

  List<Book> get books => _books;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> init() async {
    try {
      _books = await _repository.loadBooks();
    } catch (e) {
      _error = 'Could not load books: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

/// The signed-in home screen: book list + logout.
///
/// [@assistedInject] supplies [viewModelFactory] from the session graph;
/// [onLogout] is supplied by [AuthGate] at build time — it is what lets
/// this widget end the session without knowing how sessions are managed.
class HomePage extends StatelessWidget {
  @assistedInject
  const HomePage({@assisted super.key, required this.viewModelFactory, @assisted required this.onLogout});

  final ViewModelFactory<BooksViewModel> viewModelFactory;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return viewModelFactory(
      init: (vm) => vm.init(),
      loading: const Center(child: CircularProgressIndicator()),
      builder: (context, vm, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('My Books'),
            actions: [IconButton(onPressed: onLogout, tooltip: 'Log out', icon: const Icon(Icons.logout))],
          ),
          body: vm.error != null
              ? Center(
                  child: Text(vm.error!, style: const TextStyle(color: Colors.red)),
                )
              : ListView.builder(
                  itemCount: vm.books.length,
                  itemBuilder: (context, index) {
                    final Book book = vm.books[index];
                    return ListTile(title: Text(book.title), subtitle: Text(book.author));
                  },
                ),
        );
      },
    );
  }
}
