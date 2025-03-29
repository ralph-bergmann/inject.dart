import 'package:flutter_demo/src/data/repositories/counter_repository.dart';
import 'package:flutter_demo/src/features/home/my_home_page_view_model.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:test/test.dart';

import 'data/repositories/fake_repository.dart';
import 'view_model_test.inject.dart' as g;

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
