## 1.2.1

- add missing documentation

## 1.2.0

- Add `@subcomponent` and `@Module(subcomponents: ...)` for encapsulated dependency subgraphs.
- Add `@subcomponentFactory` / `SubcomponentFactory`: an explicit factory for a `@subcomponent` that
  replaces the synthesized `<Name>Factory`. Its method's non-module parameters become instance
  bindings in the subcomponent graph (Dagger's `@BindsInstance` equivalent), letting runtime values
  (e.g. a login token) flow into a subcomponent without wrapping them in a module constructor.
- Add `@Module(includes: [...])`: a module can fold in other modules' providers, transitively, with
  cycle detection and dedup-by-type for diamond includes. Lets a library author ship one public
  "umbrella" module backed by several internal modules, so a consuming app only has to list the
  umbrella module. A component's/subcomponent's own directly-listed modules always take precedence
  over anything pulled in through `includes`.

## 1.1.0

- Add provision listeners: the `@provisionListener` annotation and the `ProvisionListener` interface.
- Export the annotation classes (`Inject`, `Module`, `Singleton`, `Asynchronous`, `Assisted`, `AssistedInject`, `AssistedFactory`) alongside the existing `const` instances.
- Works with the fully rewritten `inject_generator`.

## 1.0.1

- fix analyzer warnings
  - unintended_html_in_doc_comment
  - implementation_imports
  - prefer_function_declarations_over_variables


## 1.0.0

- first stable release


## 1.0.0-alpha.5

- update to Dart 3.6.0
- update dependencies

## 1.0.0-alpha.4

- update to Dart 3
- use late final or const in generated code where possible

## 1.0.0-alpha.3

- Improve pubspec description
- Update sdk constraints

## 1.0.0-alpha.2

- Improve documentation

## 1.0.0-alpha.1

- Initial release
