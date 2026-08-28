/// Flutter integration for the inject.dart dependency injection framework.
///
/// Provides `ViewModelFactory`, `ViewModelBuilder`, and related types for
/// binding injected ViewModels to the Flutter widget lifecycle, plus
/// `SubcomponentBuilder` for owning a `@subcomponent` graph's lifecycle
/// (e.g. a login session) from a widget.
library;

export 'src/subcomponent_builder.dart';
export 'src/view_model_factory.dart';
