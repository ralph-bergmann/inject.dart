import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inject_flutter/inject_flutter.dart';

/// A plain (non-`ChangeNotifier`) stand-in for a generated `@subcomponent`
/// graph object.
class _Session {
  _Session(this.id);

  final int id;
}

void main() {
  group('SubcomponentBuilder', () {
    testWidgets('synchronous create builds immediately, with no loading frame', (tester) async {
      var createCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SubcomponentBuilder<_Session>(
            create: () {
              createCalls++;
              return _Session(1);
            },
            loading: const Text('loading'),
            builder: (context, session, _) => Text('session ${session.id}'),
          ),
        ),
      );

      expect(createCalls, 1);
      expect(find.text('session 1'), findsOneWidget);
      expect(find.text('loading'), findsNothing);
    });

    testWidgets('asynchronous create shows loading, then builder on success', (tester) async {
      final completer = Completer<_Session>();

      await tester.pumpWidget(
        MaterialApp(
          home: SubcomponentBuilder<_Session>(
            create: () => completer.future,
            loading: const Text('loading'),
            builder: (context, session, _) => Text('session ${session.id}'),
          ),
        ),
      );

      expect(find.text('loading'), findsOneWidget);
      expect(find.textContaining('session'), findsNothing);

      completer.complete(_Session(42));
      await tester.pumpAndSettle();

      expect(find.text('session 42'), findsOneWidget);
      expect(find.text('loading'), findsNothing);
    });

    testWidgets('asynchronous create failure shows the error builder', (tester) async {
      final completer = Completer<_Session>();

      await tester.pumpWidget(
        MaterialApp(
          home: SubcomponentBuilder<_Session>(
            create: () => completer.future,
            loading: const Text('loading'),
            error: (context, error, stackTrace) => Text('error: $error'),
            builder: (context, session, _) => Text('session ${session.id}'),
          ),
        ),
      );

      completer.completeError('boom');
      await tester.pumpAndSettle();

      expect(find.text('error: boom'), findsOneWidget);
      expect(find.text('loading'), findsNothing);
    });

    testWidgets(
      'asynchronous create failure without an error builder reports via FlutterError '
      'and stays on the loading background',
      (tester) async {
        final completer = Completer<_Session>();
        final FlutterExceptionHandler? originalOnError = FlutterError.onError;
        final reported = <FlutterErrorDetails>[];
        FlutterError.onError = reported.add;
        addTearDown(() => FlutterError.onError = originalOnError);

        await tester.pumpWidget(
          MaterialApp(
            home: SubcomponentBuilder<_Session>(
              create: () => completer.future,
              loading: const Text('loading'),
              builder: (context, session, _) => Text('session ${session.id}'),
            ),
          ),
        );

        completer.completeError(StateError('boom'));
        await tester.pumpAndSettle();

        expect(find.text('loading'), findsOneWidget);
        expect(reported, hasLength(1));
        expect(reported.single.exception, isA<StateError>());
      },
    );

    testWidgets('dispose is called with the instance when the widget is removed (synchronous create)', (
      tester,
    ) async {
      _Session? disposedWith;

      await tester.pumpWidget(
        MaterialApp(
          home: SubcomponentBuilder<_Session>(
            create: () => _Session(7),
            dispose: (session) => disposedWith = session,
            builder: (context, session, _) => Text('session ${session.id}'),
          ),
        ),
      );

      expect(disposedWith, isNull);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      expect(disposedWith?.id, 7);
    });

    testWidgets('late async completion after dispose is dropped silently: no setState, no dispose call', (
      tester,
    ) async {
      final completer = Completer<_Session>();
      var disposeCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SubcomponentBuilder<_Session>(
            create: () => completer.future,
            dispose: (_) => disposeCalls++,
            builder: (context, session, _) => Text('session ${session.id}'),
          ),
        ),
      );

      // Remove the widget from the tree before the pending `create` resolves.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Resolve afterwards — must not throw ("setState after dispose") and
      // must not invoke `dispose` (nothing was ever "created" from this
      // widget's perspective).
      completer.complete(_Session(99));
      await tester.pumpAndSettle();

      expect(disposeCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a key change disposes the old instance and creates a new one', (tester) async {
      final disposedIds = <int>[];
      var nextId = 0;

      Widget build(Key key) => MaterialApp(
        home: SubcomponentBuilder<_Session>(
          key: key,
          create: () => _Session(nextId++),
          dispose: (session) => disposedIds.add(session.id),
          builder: (context, session, _) => Text('session ${session.id}'),
        ),
      );

      await tester.pumpWidget(build(const ValueKey('a')));
      expect(find.text('session 0'), findsOneWidget);
      expect(disposedIds, isEmpty);

      await tester.pumpWidget(build(const ValueKey('b')));
      expect(disposedIds, [0]);
      expect(find.text('session 1'), findsOneWidget);
    });

    testWidgets('a rebuild with the same key retains the instance and does not call create again', (tester) async {
      var createCalls = 0;

      Widget build(String label) => MaterialApp(
        home: SubcomponentBuilder<_Session>(
          key: const ValueKey('same'),
          create: () {
            createCalls++;
            return _Session(1);
          },
          builder: (context, session, _) => Text('$label ${session.id}'),
        ),
      );

      await tester.pumpWidget(build('first'));
      expect(find.text('first 1'), findsOneWidget);
      expect(createCalls, 1);

      await tester.pumpWidget(build('second'));
      expect(find.text('second 1'), findsOneWidget);
      expect(createCalls, 1);
    });

    testWidgets('dispose is called with the resolved instance after an asynchronous create succeeds', (
      tester,
    ) async {
      final completer = Completer<_Session>();
      _Session? disposedWith;

      await tester.pumpWidget(
        MaterialApp(
          home: SubcomponentBuilder<_Session>(
            create: () => completer.future,
            dispose: (session) => disposedWith = session,
            builder: (context, session, _) => Text('session ${session.id}'),
          ),
        ),
      );

      completer.complete(_Session(13));
      await tester.pumpAndSettle();
      expect(find.text('session 13'), findsOneWidget);
      expect(disposedWith, isNull);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      expect(disposedWith?.id, 13);
    });

    testWidgets('the child widget is passed through to builder unchanged', (tester) async {
      const childWidget = Text('child');

      await tester.pumpWidget(
        MaterialApp(
          home: SubcomponentBuilder<_Session>(
            create: () => _Session(1),
            builder: (context, session, child) => Column(children: [Text('session ${session.id}'), child!]),
            child: childWidget,
          ),
        ),
      );

      expect(find.text('session 1'), findsOneWidget);
      expect(find.byWidget(childWidget), findsOneWidget);
    });
  });
}
