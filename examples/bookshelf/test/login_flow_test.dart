import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_component.dart';

void main() {
  testWidgets('login shows the book list from the fake backend, logout returns to sign-in', (tester) async {
    final component = TestComponent.create();

    await tester.pumpWidget(MaterialApp(home: component.authGateFactory.create()));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'alice');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'hunter2');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    // Successful login swaps in the session-scoped home page.
    expect(find.text('My Books'), findsOneWidget);
    expect(find.text('Fake Book One'), findsOneWidget);
    expect(find.text('Fake Book Two'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    // Logout drops the session and returns to the login form.
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('wrong password stays on the login form and shows an error', (tester) async {
    final component = TestComponent.create();

    await tester.pumpWidget(MaterialApp(home: component.authGateFactory.create()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'alice');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'wrong-password');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.textContaining('Login failed'), findsOneWidget);
    expect(find.text('My Books'), findsNothing);
  });
}
