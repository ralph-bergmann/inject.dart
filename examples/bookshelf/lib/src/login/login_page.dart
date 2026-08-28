import 'package:bookshelf_core/bookshelf_core.dart';
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:inject_flutter/inject_flutter.dart';

import 'login_view_model.dart';

part 'login_page.factory.dart';

/// Username/password form.
///
/// On success, hands the resulting [Credentials] to [onLoggedIn] — it is
/// [AuthGate], not this widget, that turns those credentials into a session.
class LoginPage extends StatelessWidget {
  @assistedInject
  const LoginPage({@assisted super.key, required this.viewModelFactory, @assisted required this.onLoggedIn});

  final ViewModelFactory<LoginViewModel> viewModelFactory;
  final ValueChanged<Credentials> onLoggedIn;

  @override
  Widget build(BuildContext context) {
    return viewModelFactory(
      builder: (context, vm, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Sign in')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: vm.usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: vm.passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                if (vm.error != null) Text(vm.error!, style: const TextStyle(color: Colors.red)),
                ElevatedButton(
                  onPressed: vm.submitting
                      ? null
                      : () async {
                          final Credentials? credentials = await vm.login();
                          if (credentials != null) {
                            onLoggedIn(credentials);
                          }
                        },
                  child: const Text('Log in'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
