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
  required ViewModelWidgetBuilder<T> builder,
  Widget? child,
});

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
/// 3. Rebuilds the UI whenever the ViewModel notifies its listeners
///
/// You typically won't instantiate this class directly. Instead, use the
/// [ViewModelFactory] that's generated and injected into your widgets.
class ViewModelBuilder<T extends ChangeNotifier> extends StatefulWidget {
  /// Creates a widget that rebuilds when the provided ViewModel changes.
  ///
  /// The [viewModelProvider] is used to obtain the ViewModel instance.
  /// The [builder] function rebuilds the widget whenever the ViewModel changes.
  /// The optional [child] widget is passed to the [builder] and can be used for
  /// optimization when parts of the widget subtree don't depend on the ViewModel.
  const ViewModelBuilder({
    super.key,
    required this.viewModelProvider,
    required this.builder,
    this.child,
  });

  /// Provider that creates and returns the ViewModel instance.
  final Provider<T> viewModelProvider;

  /// Builder function that constructs the widget tree based on the ViewModel.
  final ViewModelWidgetBuilder<T> builder;

  /// An optional child widget that doesn't depend on the ViewModel.
  final Widget? child;

  @override
  State<ViewModelBuilder<T>> createState() => _ViewModelBuilderState<T>();
}

class _ViewModelBuilderState<T extends ChangeNotifier> extends State<ViewModelBuilder<T>> {
  late final T _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModelProvider.get();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) => widget.builder(context, _viewModel, child),
        child: widget.child,
      );
}
