import 'package:inject_lints/src/rules/avoid_manual_view_model_builder.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidManualViewModelBuilderTest);
  });
}

@reflectiveTest
class AvoidManualViewModelBuilderTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = AvoidManualViewModelBuilder();
    super.setUp();
  }

  Future<void> test_constructedByHand() => assertLints(
    r'''
import 'package:flutter/widgets.dart';
import 'package:inject_flutter/inject_flutter.dart';

Widget f() => ViewModelBuilder<Object>(builder: (context, viewModel) => context.widget);
''',
    ['ViewModelBuilder<Object>'],
  );

  Future<void> test_createdByFactory() => assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:inject_flutter/inject_flutter.dart';

Widget f(ViewModelFactory<Object> factory) => factory(builder: (context, viewModel) => context.widget);
''');
}
