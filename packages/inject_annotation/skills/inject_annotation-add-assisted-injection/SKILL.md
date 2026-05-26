---
name: inject_annotation-add-assisted-injection
description: Adds assisted injection in inject.dart for objects whose constructor mixes graph-provided dependencies with runtime arguments supplied at call time — using @assistedInject on the constructor, @assisted on the runtime parameters, and an @assistedFactory interface (or a generator-synthesized factory). Use when some constructor parameters are known only at runtime (an id, a model, a Key), when the user says "assisted injection", "factory with runtime parameters", or needs to pass arguments into an injected object.
license: BSD-3-Clause
metadata:
  author: ralph-bergmann
  package: inject.dart
  last_modified: "2026-05-25"
---

# Add assisted injection

Assisted injection is for objects whose constructor needs **both** dependencies
from the graph **and** values known only at runtime (an entity id, a selected
model, a Flutter `Key`). inject.dart provides the graph parameters; the caller
passes the rest through a generated **factory**.

## Annotations

- `@assistedInject` — on the constructor (replaces `@inject` for this class).
- `@assisted` — on each parameter supplied at call time.
- `@assistedFactory` — on an abstract factory interface (optional; the generator
  can synthesize one).

## Task progress

- [ ] 1. Annotate the constructor and runtime parameters
- [ ] 2. Provide a factory (explicit interface or synthesized)
- [ ] 3. Add the `part` directive
- [ ] 4. Expose the factory from the component
- [ ] 5. Call the factory; regenerate and verify

## Steps

### 1. Annotate the constructor

Mark the constructor `@assistedInject` and tag every runtime parameter
`@assisted`. Unannotated parameters are injected from the graph.

```dart
class ProductCard {
  @assistedInject
  const ProductCard(
    this._analytics,        // injected from the graph
    @assisted this.product, // supplied at call time
  );

  final AnalyticsService _analytics;
  final Product product;
}
```

### 2. Provide a factory

**Option A — synthesized factory (preferred).** Annotate only the constructor
with `@assistedInject` and declare **no** factory interface. The generator
synthesizes `<ClassName>Factory` with a `create(...)` method taking the
`@assisted` parameters. For `ProductCard` you get
`ProductCardFactory.create(Product product)` — no boilerplate to write. This is
the style used throughout the examples (`HomePageFactory`, `MyAppFactory`).

**Option B — explicit interface (only when you need a custom factory type).**
Write it yourself only if you need a specific factory interface to reference.
Annotate an abstract class with `@assistedFactory`; it must declare **exactly
one** abstract method (any name, e.g. `create` or `build`) whose return type is
the assisted-injected type and whose parameters match the `@assisted`
parameters exactly (type, name and positional/named/optional shape).

```dart
@assistedFactory
abstract class ProductCardFactory {
  ProductCard create(Product product);
}
```

### 3. Add the `part` directive

The factory implementation is emitted as a `part`. In the file that declares the
assisted-injected class:

```dart
part 'product_card.factory.dart';
```

### 4. Expose the factory from the component

Inject the **factory**, not the class itself:

```dart
@Component([AppModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  ProductCardFactory get productCardFactory;
}
```

### 5. Call the factory

```dart
final card = component.productCardFactory.create(product);
```

```bash
dart run build_runner build --delete-conflicting-outputs
dart analyze
```

## Flutter widget example

A widget that needs both injected services and a runtime `Key`/`title`:

```dart
part 'home_page.factory.dart';

class HomePage extends StatelessWidget {
  @assistedInject
  const HomePage({
    @assisted super.key,
    @assisted required this.title,
    required this.viewModelFactory, // injected from the graph
  });

  final String title;
  final ViewModelFactory<CounterViewModel> viewModelFactory;
  // ...
}

// Synthesized: HomePageFactory.create({Key? key, required String title})
```

## Common mistakes

- **Factory method parameters don't match the `@assisted` parameters** (type,
  name, or named-vs-positional) → build error. Keep the signatures identical.
- **More than one method on the `@assistedFactory`** → exactly one is allowed.
- **Missing `part '<file>.factory.dart';`** → the generated factory has nowhere
  to attach.
- **Using `@inject` instead of `@assistedInject`** → the class is treated as a
  plain injectable; runtime parameters can't be passed.
- **Injecting the class instead of its factory** → inject the factory and call
  it with the runtime arguments.
