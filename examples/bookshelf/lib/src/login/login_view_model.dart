import 'package:bookshelf_auth/bookshelf_auth.dart';
import 'package:bookshelf_core/bookshelf_core.dart';
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

/// Root-graph ViewModel backing [LoginPage].
///
/// Depends on [AuthRepository], a root-graph singleton. This ViewModel never
/// touches `SessionComponent` itself — `AuthGate` is the one place that
/// turns a successful login into a session.
@inject
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required this._authRepository});

  final AuthRepository _authRepository;

  final TextEditingController usernameController = TextEditingController(text: 'alice');
  final TextEditingController passwordController = TextEditingController(text: 'hunter2');

  bool _submitting = false;
  String? _error;
  bool _disposed = false;

  bool get submitting => _submitting;
  String? get error => _error;

  /// Attempts a login with the current field values.
  ///
  /// Returns the resulting [Credentials] on success, or `null` after
  /// recording a user-facing [error].
  Future<Credentials?> login() async {
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      return await _authRepository.login(usernameController.text, passwordController.text);
    } catch (e) {
      _error = 'Login failed: $e';
      return null;
    } finally {
      _submitting = false;
      // The await above may outlive this ViewModel (e.g. the widget was
      // removed from the tree while the login request was in flight) —
      // notifying a disposed ChangeNotifier throws, so guard it.
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
