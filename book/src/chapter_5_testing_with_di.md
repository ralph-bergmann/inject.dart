# Testing with Dependency Injection

After implementing state management with dependency injection, the next natural
step is to explore how our architecture enhances testability. One of the most
significant benefits of dependency injection is how it simplifies testing by
allowing us to substitute implementations without modifying production code.

In this chapter, we'll see how to leverage inject.dart's capabilities to create
effective tests for our counter application, showing how each layer can be
tested in isolation while maintaining confidence in the entire system.

## Understanding Testing With Dependency Injection

Dependency injection dramatically improves testability because components don't
create their dependencies directly — they receive them. This means we can
provide alternative implementations during tests, such as:

1. **Mock/Fake objects** that simulate behavior in controlled ways
2. **Test doubles** that record interactions for verification
3. **In-memory implementations** that eliminate external dependencies

This approach allows us to write focused tests that verify specific behaviors
without worrying about side effects or external systems.

## Implementing Repository Tests

Let's start by testing our `CounterRepository` class. Since this repository
depends on a `Database`, we'll create a test-specific implementation of the
database.

### Creating a Test Component

First, we need to create a test-specific dependency injection component:

```dart
@Component([TestModule])
abstract class TestComponent {
  static const create = g.TestComponent$Component.create;

  @inject
  CounterRepository get counterRepository;

  @inject
  Database get database;
}

@module
class TestModule {
  @provides
  @singleton
  Database provideDatabase() => FakeDatabase();
}
```

This `TestComponent` serves several important roles:

1. It creates a separate dependency graph for our tests
2. It uses a `TestModule` to provide test-specific implementations
3. It exposes the components we need to access in our tests
4. The `@singleton` annotation ensures we use the same test database instance
   throughout the test

The `TestModule` is particularly important — it overrides the normal database
implementation with our test-specific version. This substitution happens without
requiring any changes to our `CounterRepository` class, demonstrating the power
of dependency injection for testing.

### Implementing the Fake Database

Our `FakeDatabase` class implements the same interface as the production
database but provides behaviors suitable for testing:

```dart
class FakeDatabase implements Database {
   int _count = 0;

   @override
   Future<void> updateCount(int count) async {
      _count = count;
   }

   @override
   Future<int> selectCount() {
      return Future.value(_count);
   }
}
```

The fake database provides:

1. An in-memory implementation that doesn't rely on external systems
2. Predictable behavior for tests to verify
3. The same interface as the production database

By implementing the same interface, we ensure our tests verify behavior that
will work correctly with the real implementation.

### Writing the Repository Test

Now we can write tests for our repository using the test component:

```dart
void main() {
  group('CounterRepository Test', () {
    late final CounterRepository repository;

    setUp(() {
      final component = TestComponent.create();
      repository = component.counterRepository;
    });

    test('test counter repository', () async {
      var count = await repository.count;
      expect(count, 0);

      await repository.increaseCount();
      count = await repository.count;
      expect(count, 1);
    });
  });
}
```

The test follows these steps:

1. In `setUp`, we create a test component that injects our test dependencies
2. We retrieve the repository from the component, which receives the test
   database
3. We test the repository's behaviors by verifying that:
    - The initial count is `0`
    - After calling `increaseCount()`, the count increases to `1`

This test verifies the repository functions correctly with a controlled database
implementation. If the repository's logic is incorrect, the test will fail, but
we've eliminated external factors that could cause flaky tests.

## Testing View Models

The same approach works for testing view models. By injecting fake repositories,
we can test view model behavior in isolation:

```dart
void main() {
   group('MyHomePageViewModel Test', () {
      late final MyHomePageViewModel viewModel;

      setUp(() {
         final component = ViewModelTestComponent.create();
         viewModel = component.homeViewModel;
      });

      test('increaseCount updates state from repository', () async {
         expect(viewModel.count, 0);

         await viewModel.increaseCount();
         expect(viewModel.count, 1);
      });
   });
}

@Component([TestModule])
abstract class ViewModelTestComponent {
   static const create = g.ViewModelTestComponent$Component.create;

   @inject
   MyHomePageViewModel get homeViewModel;
}

@module
class TestModule {
   @provides
   @singleton
   CounterRepository provideCounterRepository() => FakeCounterRepository();
}
```

This test demonstrates several key techniques:

1. Creating a test-specific component for view model testing
2. Providing a fake repository that controls what data the view model sees
3. Verifying state changes in the view model

This pattern allows us to test complex view model logic without worrying about
actual data persistence or external services.

## Beyond Unit Tests

While we've focused on unit testing in this chapter, it's important to note that
dependency injection provides the same benefits for all types of tests,
including:

- **Integration tests** that verify multiple components working together
- **Widget tests** in Flutter that ensure UI components behave correctly
- **End-to-end tests** that simulate user flows through the application

The same principles apply: create test-specific components, override
dependencies with test implementations, and verify behavior in a controlled
environment. This flexibility makes dependency injection an invaluable tool for
comprehensive testing strategies across all layers of your application.

## Best Practices for Testing with DI

Through our examples, we've demonstrated several best practices for testing with
dependency injection:

1. **Create separate test components**: Define components specifically for
   testing that provide test-specific implementations.

2. **Use modules to override dependencies**: Test modules allow you to
   substitute test implementations without changing production code.

3. **Test each layer appropriately**: Write unit tests for repositories and
   view models, integration tests for component interaction, and widget tests
   for UI behavior.

4. **Make dependencies explicit**: When dependencies are injected explicitly,
   they become easier to substitute in tests.

5. **Design for testability**: Components that expect their dependencies to be
   injected are inherently more testable than those that create dependencies
   directly.

## Conclusion

Dependency injection dramatically improves testability by making dependencies
explicit and substitutable. With inject.dart, we can create test-specific
dependency graphs that provide controlled implementations for testing.

Our repository test example demonstrated how to:

1. Create a test-specific component and module
2. Provide a test implementation of dependencies
3. Test component behavior in isolation

This approach to testing produces more reliable tests that focus on the behavior
of specific components without being affected by external systems or side
effects.

### Complete Example

You can find the complete source code for all examples in this chapter in
the [`examples/flutter_demo`](https://github.com/ralph-bergmann/inject.dart/tree/master/examples/flutter_demo)
folder of the inject.dart repository. This working implementation
demonstrates all the patterns and practices we've discussed.
