import 'dart:async';

import 'package:flutter/widgets.dart';

/// Signature for the function that creates the subcomponent instance for a
/// [SubcomponentBuilder].
///
/// Called exactly once, in [State.initState] — never again for the lifetime
/// of that `State` (only a widget [Key] change forces a fresh `State`, and
/// therefore a fresh call). May be synchronous or return a [Future]:
/// [SubcomponentBuilder] awaits an asynchronous result, showing
/// [SubcomponentBuilder.loading] while it runs and [SubcomponentBuilder.error]
/// (or, if none is given, reporting through [FlutterError.reportError]) when
/// it fails.
///
/// Typically this wraps a `<Name>Factory.create(...)` call — the synthesized
/// factory's module parameters, or an explicit `@subcomponentFactory`'s
/// runtime value parameters:
///
/// ```dart
/// create: () => sessionFactory.create(credentials),
/// ```
typedef SubcomponentCreator<T> = FutureOr<T> Function();

/// Signature for the optional callback that releases a subcomponent instance
/// created by a [SubcomponentBuilder].
///
/// Called once from [State.dispose] with the subcomponent instance — never
/// with `null` and never more than once. Not called at all if an
/// asynchronous [SubcomponentBuilder.create] never resolved before the
/// widget was disposed, since no instance was ever produced from the
/// widget's perspective.
typedef SubcomponentDisposer<T> = void Function(T subcomponent);

/// Signature for the widget shown when an asynchronous [SubcomponentBuilder.create]
/// fails.
///
/// Receives the [error] and its [stackTrace] (which may be `null`).
typedef SubcomponentErrorBuilder = Widget Function(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
);

/// Signature for the builder callback used by [SubcomponentBuilder].
///
/// The builder provides the [BuildContext], the created [subcomponent], and
/// an optional [child] widget that can be incorporated for optimization.
typedef SubcomponentWidgetBuilder<T> = Widget Function(
  BuildContext context,
  T subcomponent,
  Widget? child,
);

/// A widget that owns the lifecycle of a subcomponent (a `@subcomponent`
/// graph, e.g. a login session) for as long as it stays in the tree.
///
/// This widget:
/// 1. Calls [create] exactly once, in [State.initState] — synchronously or,
///    if [create] returns a [Future], awaiting it while showing [loading]
///    (and [error] if it fails).
/// 2. Exposes the created subcomponent to [builder] once available.
/// 3. Calls [dispose] (if given) with the subcomponent instance when this
///    widget is removed from the tree, releasing every binding the
///    subcomponent held privately.
///
/// Unlike `ViewModelBuilder`, the created value is not expected to be a
/// `ChangeNotifier` — a subcomponent is a plain generated graph object, not
/// an observable. [SubcomponentBuilder] never listens to it and rebuilds
/// only when something above it in the tree rebuilds it.
///
/// The **only** way to force a new subcomponent instance is to change this
/// widget's [Key] (e.g. `ValueKey(credentials)`) — Flutter's own element
/// diffing then guarantees a fresh `State`, and therefore a fresh [create]
/// call, while an unrelated rebuild with the same key retains the existing
/// instance untouched. Compose [SubcomponentBuilder] *below* whatever branch
/// point decides when a subcomponent should exist at all (e.g. a
/// login/logout switch) — mounting it is "create", unmounting it is
/// "dispose".
///
/// Example usage — a session created on login, dropped on logout:
///
/// ```dart
/// class AuthGate extends StatefulWidget {
///   const AuthGate({super.key, required this.sessionFactory});
///
///   final SessionComponentFactory sessionFactory;
///
///   @override
///   State<AuthGate> createState() => _AuthGateState();
/// }
///
/// class _AuthGateState extends State<AuthGate> {
///   Credentials? _credentials;
///
///   @override
///   Widget build(BuildContext context) {
///     final credentials = _credentials;
///     if (credentials == null) {
///       return LoginPage(onLoggedIn: (c) => setState(() => _credentials = c));
///     }
///     return SubcomponentBuilder<SessionComponent>(
///       key: ValueKey(credentials),
///       create: () => widget.sessionFactory.create(credentials),
///       builder: (context, session, _) {
///         return HomePage(onLogout: () => setState(() => _credentials = null));
///       },
///     );
///   }
/// }
/// ```
class SubcomponentBuilder<T> extends StatefulWidget {
  /// Creates a widget that owns the lifecycle of a subcomponent.
  ///
  /// [create] is called once in [State.initState] to produce the
  /// subcomponent; it may be synchronous or asynchronous.
  /// The optional [dispose] callback is invoked with the subcomponent
  /// instance when this widget is removed from the tree.
  /// The optional [loading] widget is shown while an asynchronous [create]
  /// runs, and the optional [error] builder when it fails.
  /// The [builder] function builds the widget subtree once the subcomponent
  /// is available.
  /// The optional [child] widget is passed to [builder] and can be used for
  /// optimization when parts of the widget subtree don't depend on the
  /// subcomponent.
  const SubcomponentBuilder({
    super.key,
    required this.create,
    this.dispose,
    this.loading,
    this.error,
    required this.builder,
    this.child,
  });

  /// Creates the subcomponent instance. Called exactly once, in
  /// [State.initState].
  final SubcomponentCreator<T> create;

  /// Optional callback invoked with the subcomponent instance when this
  /// widget is removed from the tree.
  final SubcomponentDisposer<T>? dispose;

  /// Widget shown while an asynchronous [create] is still running.
  ///
  /// Ignored for a synchronous [create]. Defaults to an empty box.
  final Widget? loading;

  /// Builder for the widget shown when an asynchronous [create] fails.
  ///
  /// Ignored for a synchronous [create]. When omitted, a creation error is
  /// reported through [FlutterError.reportError] instead of being dropped.
  final SubcomponentErrorBuilder? error;

  /// Builder function that constructs the widget tree once the subcomponent
  /// is available.
  final SubcomponentWidgetBuilder<T> builder;

  /// An optional child widget that doesn't depend on the subcomponent.
  final Widget? child;

  @override
  State<SubcomponentBuilder<T>> createState() => _SubcomponentBuilderState<T>();
}

class _SubcomponentBuilderState<T> extends State<SubcomponentBuilder<T>> {
  /// The created subcomponent instance, once available.
  ///
  /// Set synchronously in [initState] when [SubcomponentBuilder.create] is
  /// synchronous, or from within the [FutureBuilder] in [build] once an
  /// asynchronous [SubcomponentBuilder.create] resolves. Stays `null` for
  /// good if this `State` is disposed before an asynchronous
  /// [SubcomponentBuilder.create] resolves — [FutureBuilder] already guards
  /// against invoking its `builder` after it has been disposed, so no extra
  /// guard is needed here.
  T? _subcomponent;

  /// Set only when [SubcomponentBuilder.create] is asynchronous; drives the
  /// [FutureBuilder] that gates the UI on subcomponent creation.
  Future<T>? _createFuture;

  @override
  void initState() {
    super.initState();
    final FutureOr<T> result = widget.create();
    if (result is Future<T>) {
      _createFuture = result;
    } else {
      _subcomponent = result;
    }
  }

  @override
  void dispose() {
    // Only call back with an instance that actually exists: a synchronous
    // `create` always populates this; an asynchronous `create` that never
    // resolved before this `State` was disposed leaves it `null` — nothing
    // was ever "created" from this widget's perspective, so there is
    // nothing to release.
    final T? subcomponent = _subcomponent;
    if (subcomponent != null) {
      widget.dispose?.call(subcomponent);
    }
    super.dispose();
  }

  Widget _buildSubcomponent(BuildContext context, T subcomponent) =>
      widget.builder(context, subcomponent, widget.child);

  @override
  Widget build(BuildContext context) {
    final T? subcomponent = _subcomponent;
    if (subcomponent != null) {
      return _buildSubcomponent(context, subcomponent);
    }

    final Future<T>? createFuture = _createFuture;
    if (createFuture == null) {
      // Unreachable: a synchronous `create` always sets `_subcomponent`
      // above, in `initState`.
      return widget.loading ?? const SizedBox.shrink();
    }

    return FutureBuilder<T>(
      future: createFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loading ?? const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          final SubcomponentErrorBuilder? errorBuilder = widget.error;
          if (errorBuilder != null) {
            return errorBuilder(context, snapshot.error!, snapshot.stackTrace);
          }
          // No error builder supplied: surface the error instead of
          // dropping it.
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: snapshot.error!,
              stack: snapshot.stackTrace,
              library: 'inject_flutter',
              context: ErrorDescription('while creating $T'),
            ),
          );
          return widget.loading ?? const SizedBox.shrink();
        }
        // Cache the resolved instance so `dispose()` (and any subsequent
        // build of this State) can see it without going through the
        // FutureBuilder again.
        final value = snapshot.data as T;
        _subcomponent = value;
        return _buildSubcomponent(context, value);
      },
    );
  }
}
