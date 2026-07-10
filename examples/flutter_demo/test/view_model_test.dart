import 'package:counter_analytics/counter_analytics.dart';
import 'package:flutter_demo/src/data/repositories/counter_repository.dart';
import 'package:flutter_demo/src/domain/models/counter.dart';
import 'package:flutter_demo/src/features/home/counter_view_model.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:test/test.dart';

import 'data/repositories/fake_repository.dart';
import 'view_model_test.inject.dart' as g;

void main() {
  group('CounterViewModel', () {
    late CounterViewModel viewModel;

    setUp(() async {
      final component = TestViewModelComponent.create();
      viewModel = component.counterViewModel;
      // Resolve the Future<int> initial count (as CounterViewModel.init does).
      await viewModel.init();
    });

    test('initial counter value is zero', () {
      expect(viewModel.counter, const Counter(value: 0));
    });

    test('increment updates counter via use case', () async {
      await viewModel.increment();
      expect(viewModel.counter.value, 1);
    });

    test('multiple increments accumulate', () async {
      await viewModel.increment();
      await viewModel.increment();
      expect(viewModel.counter.value, 2);
    });
  });
}

/// Test component for [CounterViewModel].
///
/// [TestViewModelModule] provides a fake [CounterRepository] and a fixed
/// initial count. [IncrementCounterUseCase] is wired automatically by
/// the generator since it is [@inject] and its [CounterRepository] dep is
/// satisfied by the module.
@Component([TestViewModelModule])
abstract class TestViewModelComponent {
  static const create = g.TestViewModelComponent$Component.create;

  @inject
  CounterViewModel get counterViewModel;
}

@module
class TestViewModelModule {
  @provides
  @singleton
  CounterRepository provideCounterRepository() => FakeCounterRepository();

  @provides
  Future<int> provideInitialCount() => Future.value(0);

  /// [IncrementCounterUseCase] depends on [IncrementTracker] (from the
  /// `counter_analytics` package), which needs an [AnalyticsService].
  /// Tests bind a no-op fake — same interface-swap as in production, just
  /// with a different implementation.
  @provides
  @singleton
  AnalyticsService provideAnalyticsService() => _NoOpAnalyticsService();
}

class _NoOpAnalyticsService implements AnalyticsService {
  @override
  void track(String event) {
    // Intentionally empty — tests don't report analytics.
  }
}
