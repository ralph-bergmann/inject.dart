import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:inject_annotation/inject_annotation.dart';

/// A function that creates a [ViewModelBuilder] bound to a specific ViewModel type [T].
///
/// When injected into your widgets, this factory creates a clean and intuitive API
/// for connecting ViewModels to your UI without manual lifecycle management.
///
/// The inject code generator will automatically create implementations of this
/// factory that properly handle the ViewModel lifecycle.
///
/// Example usage:
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:inject_annotation/inject_annotation.dart';
/// import 'package:inject_flutter/inject_flutter.dart';
///
/// import 'home_page_view_model.dart';
///
/// @assistedFactory
/// abstract class HomePageFactory {
///   HomePage create({Key? key});
/// }
///
/// class HomePage extends StatelessWidget {
///   @assistedInject
///   const HomePage({
///     @assisted super.key,
///     required this.viewModelFactory,
///   });
///
///   final ViewModelFactory<HomePageViewModel> viewModelFactory;
///
///   @override
///   Widget build(BuildContext context) {
///     return viewModelFactory(
///       // The initializer may be synchronous or `async`. An asynchronous one
///       // is awaited: [loading] is shown while it runs and [error] (if given)
///       // when it fails.
///       init: (viewModel) => viewModel.load(),
///       loading: const Center(child: CircularProgressIndicator()),
///       error: (context, error, _) => Center(child: Text('$error')),
///       builder: (context, viewModel, _) {
///         return Scaffold(
///           appBar: AppBar(title: Text(viewModel.title)),
///           body: Center(child: Text('Count: ${viewModel.count}')),
///           floatingActionButton: FloatingActionButton(
///             onPressed: viewModel.increment,
///             child: const Icon(Icons.add),
///           ),
///         );
///       },
///     );
///   }
/// }
/// ```
typedef ViewModelFactory<T extends ChangeNotifier> = ViewModelBuilder<T> Function({
  Key? key,
  ViewModelInitializer<T>? init,
  Widget? loading,
  ViewModelErrorBuilder? error,
  required ViewModelWidgetBuilder<T> builder,
  Widget? child,
});

/// Signature for initializing a ViewModel.
///
/// Invoked once when the ViewModel is created — a good place to trigger data
/// loading or other setup. The initializer may be **synchronous** or return a
/// [Future]: [ViewModelBuilder] awaits an asynchronous initializer, showing
/// [ViewModelBuilder.loading] while it runs and [ViewModelBuilder.error] (or, if
/// none is given, reporting through [FlutterError.reportError]) when it fails.
typedef ViewModelInitializer<T extends ChangeNotifier> = FutureOr<void> Function(T viewModel);

/// Signature for the widget shown when an asynchronous [ViewModelInitializer] fails.
///
/// Receives the [error] and its [stackTrace] (which may be `null`).
typedef ViewModelErrorBuilder = Widget Function(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
);

/// Signature for the builder callback used by [ViewModelBuilder].
///
/// The builder provides the [BuildContext], the [viewModel] instance, and
/// an optional [child] widget that can be incorporated for optimization.
typedef ViewModelWidgetBuilder<T extends ChangeNotifier> = Widget Function(
  BuildContext context,
  T viewModel,
  Widget? child,
);

/// A widget that binds a ViewModel to a UI, automatically handling its lifecycle
/// and rebuilding the UI when the ViewModel's state changes.
///
/// This widget:
/// 1. Obtains the ViewModel instance from the provided [Provider]
/// 2. Manages the ViewModel's lifecycle (instantiation and disposal)
/// 3. Runs [init] once. A synchronous [init] (or none) builds immediately; an
///    asynchronous [init] is awaited via a [FutureBuilder] — [loading] is shown
///    while it runs and [error] when it fails.
/// 4. Rebuilds the UI whenever the ViewModel notifies its listeners
///
/// You typically won't instantiate this class directly. Instead, use the
/// [ViewModelFactory] that's generated and injected into your widgets.
class ViewModelBuilder<T extends ChangeNotifier> extends StatefulWidget {
  /// Creates a widget that rebuilds when the provided ViewModel changes.
  ///
  /// The [viewModelProvider] is used to obtain the ViewModel instance.
  /// The [builder] function rebuilds the widget whenever the ViewModel changes.
  /// The optional [init] function is called once when the ViewModel is created;
  /// an asynchronous [init] is awaited before [builder] is shown.
  /// The optional [loading] widget is shown while an asynchronous [init] runs,
  /// and the optional [error] builder when it fails.
  /// The optional [child] widget is passed to the [builder] and can be used for
  /// optimization when parts of the widget subtree don't depend on the ViewModel.
  const ViewModelBuilder({
    super.key,
    required this.viewModelProvider,
    this.init,
    this.loading,
    this.error,
    required this.builder,
    this.child,
  });

  /// Provider that creates and returns the ViewModel instance.
  final Provider<T> viewModelProvider;

  /// Optional initializer function called once when the ViewModel is created.
  ///
  /// May be synchronous or asynchronous; see [ViewModelInitializer].
  final ViewModelInitializer<T>? init;

  /// Widget shown while an asynchronous [init] is still running.
  ///
  /// Ignored for a synchronous (or absent) [init]. Defaults to an empty box.
  final Widget? loading;

  /// Builder for the widget shown when an asynchronous [init] fails.
  ///
  /// Ignored for a synchronous (or absent) [init]. When omitted, an init error
  /// is reported through [FlutterError.reportError] instead of being dropped.
  final ViewModelErrorBuilder? error;

  /// Builder function that constructs the widget tree based on the ViewModel.
  final ViewModelWidgetBuilder<T> builder;

  /// An optional child widget that doesn't depend on the ViewModel.
  final Widget? child;

  @override
  State<ViewModelBuilder<T>> createState() => _ViewModelBuilderState<T>();
}

class _ViewModelBuilderState<T extends ChangeNotifier> extends State<ViewModelBuilder<T>> {
  late final T _viewModel;

  /// Set only when [ViewModelBuilder.init] is asynchronous; drives the
  /// [FutureBuilder] that gates the UI on initialization.
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModelProvider.get();

    final FutureOr<void>? result = widget.init?.call(_viewModel);
    if (result is Future<void>) {
      _initFuture = result;
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Widget _buildViewModel(BuildContext context) => ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) => widget.builder(context, _viewModel, child),
        child: widget.child,
      );

  @override
  Widget build(BuildContext context) {
    final Future<void>? initFuture = _initFuture;
    if (initFuture == null) {
      // Synchronous (or absent) init — nothing to await, build immediately.
      return _buildViewModel(context);
    }
    return FutureBuilder<void>(
      future: initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loading ?? const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          final ViewModelErrorBuilder? errorBuilder = widget.error;
          if (errorBuilder != null) {
            return errorBuilder(context, snapshot.error!, snapshot.stackTrace);
          }
          // No error builder supplied: surface the error instead of dropping it.
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: snapshot.error!,
              stack: snapshot.stackTrace,
              library: 'inject_flutter',
              context: ErrorDescription('while initializing $T'),
            ),
          );
          return widget.loading ?? const SizedBox.shrink();
        }
        return _buildViewModel(context);
      },
    );
  }
}
