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
