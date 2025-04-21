import 'dart:async';

import 'package:inject_annotation/inject_annotation.dart';
import 'package:inject_example_coffee/src/coffee_maker.dart';
import 'package:inject_example_coffee/src/drip_coffee_module.dart';
import 'package:inject_example_coffee/src/electric_heater.dart';
import 'package:inject_example_coffee/src/heater.dart';
import 'package:test/test.dart';

import 'coffee_app_test.inject.dart' as g;

List<String> _printLog = <String>[];

void main() {
  group('overriding', () {
    setUp(() {
      _printLog.clear();
    });

    test(
      'can be done by mixing test modules',
      _interceptPrint(() async {
        final coffee = TestCoffee.create(
          dripCoffeeModule: DripCoffeeModule(),
          testModule: TestModule(),
        );
        (await coffee.getCoffeeMaker()).brew();
        expect(_printLog, [
          'test heater turned on',
          ' [_]P coffee! [_]P',
          ' Thanks for using TestCoffeeMachine by Coffee by Dart Inc.',
        ]);
      }),
    );
  });
}

/// Overrides production services.
@module
class TestModule {
  /// Let's override what the [Heater] does.
  @provides
  Heater testHeater(Electricity _) => _TestHeater();

  /// Let's also override the model name.
  @modelName
  @provides
  String testModel() => 'TestCoffeeMachine';
}

class _TestHeater implements Heater {
  @override
  bool isHot = false;

  @override
  void on() {
    print('test heater turned on');
    isHot = true;
  }

  @override
  void off() {
    isHot = false;
  }
}

/// Demonstrates overriding dependencies in a test by mixing in test modules.
@Component(modules: [DripCoffeeModule, TestModule])
abstract class TestCoffee {
  /// Note test modules being used.
  static const create = g.TestCoffee$Component.create;

  /// Provides a coffee maker.
  @inject
  Future<CoffeeMaker> getCoffeeMaker();
}

/// Forwards [print] messages to [_printLog].
dynamic _interceptPrint(Function() testFn) {
  return () {
    return Zone.current.fork(
      specification: ZoneSpecification(
        print: (_, __, ___, message) {
          _printLog.add(message);
        },
      ),
    ).run(testFn);
  };
}
