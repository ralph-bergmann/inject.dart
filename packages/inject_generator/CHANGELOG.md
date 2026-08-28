## 1.2.1

- Fix generated imports for outputs outside `lib/`: when a component lives in `example/`, `tool/`,
  etc. and references a type from the same package's `lib/`, the generator now emits a `package:`
  import instead of a broken relative path (`../src/…`). Previously only `test/` was special-cased.

## 1.2.0

- Add support for `@subcomponent` and `@Module(subcomponents: ...)` — encapsulated dependency
  subgraphs with parent-binding inheritance, per-subcomponent-instance singletons, and a
  synthesized `<Name>Factory` bound in the parent graph. See the README section
  "Encapsulating subgraphs" for usage.
- Add support for `@subcomponentFactory` — an explicit factory for a `@subcomponent` that replaces
  the synthesized `<Name>Factory`. Its method's non-module parameters become instance bindings in
  the subcomponent graph (Dagger's `@BindsInstance` equivalent), letting runtime values flow into a
  subcomponent without wrapping them in a module constructor. Requires `inject_annotation ^1.2.0`.
- Add support for `@Module(includes: [...])` — umbrella modules. Listing a module that `includes`
  other modules pulls in all of their providers transitively, exactly as if every included module
  had been listed directly, with cycle detection and dedup-by-type when the same module is
  reachable through more than one include path. Requires `inject_annotation ^1.2.0`. See the
  README section "Umbrella modules" for usage.

## 1.1.1

* fix dependency conflict with flutter_test

## 1.1.0

- Full rewrite of the generator: new Analysis → Validation → Codegen pipeline.

## 1.0.2

* Added support for ViewModel initialization via an optional `init` callback in `ViewModelFactory`

```dart
@override
Widget build(BuildContext context) {
  return viewModelFactory(
    // Initialize the ViewModel when it's created
    init: (viewModel) {
      // Perfect place to trigger data loading
      viewModel.loadData();
    },
    builder: (context, viewModel, _) {
      return Scaffold(
        appBar: AppBar(title: Text(viewModel.title)),
        body: viewModel.isLoading 
          ? const CircularProgressIndicator()
          : ListView.builder(
              itemCount: viewModel.items.length,
              itemBuilder: (context, index) => 
                ItemTile(item: viewModel.items[index]),
            ),
      );
    },
  );
}
```

## 1.0.1

- fix analyzer warnings
  - unintended_html_in_doc_comment
  - implementation_imports
  - prefer_function_declarations_over_variables


## 1.0.0

- first stable release


## 1.0.0-alpha.8

- Improved code generation time

  The `build_runner` process has been optimized to reduce code generation
  time. In the standard workflow, `build_runner` processes all files in the
  project and provides them to the code generator, which then generates a
  summary for each Dart file. Version 1.0.0-alpha.7 already improved
  performance by filtering out Dart files that don't import
  `package:inject_annotation`. This release takes optimization further by
  addressing the time-consuming process of finding `Component`
  declarations. Previously, the generator had to read all summaries to
  locate these `Component`s, which serve as the root of the dependency
  graph and the starting point for code generation. Now, `Component`
  declarations are extracted from summaries during the first step and
  stored in a dedicated file. This means the second step of the process can
  begin immediately with the component files rather than searching through
  all summaries, resulting in significantly faster generation times.

## 1.0.0-alpha.7

- improve code generator

  skip Dart files which don't import `package:inject_annotation`

## 1.0.0-alpha.6

- Improve LookupKey.fromDartType to support more DartTypes
- fix melos scripts

## 1.0.0-alpha.5

- update to Dart 3.6.0
- update dependencies

## 1.0.0-alpha.4

- update to Dart 3
- use late final or const in generated code where possible

## 1.0.0-alpha.3

- Add support for injecting methods
  ```dart
  void main() {
    final mainComponent = g.MainComponent$Component.create();
    final add = mainComponent.add;
    final sum = add(1, 2);
    print(sum);
  }
  
  @Component([MainModule])
  abstract class MainComponent {
    static const create = g.MainComponent$Component.create;
  
    Addition get add;
  }
  
  typedef Addition = int Function(int a, int b);
  
  @module
  class MainModule {
    @provides
    Addition provideAddition() => _add;
  }
  
  int _add(int a, int b) => a + b;
  ```

## 1.0.0-alpha.2

- Fix injection of generic types
- Update sdk constraints

## 1.0.0-alpha.1

- Initial release
