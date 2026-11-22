import 'package:inject_lints/src/rules/avoid_inline_qualifier.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidInlineQualifierTest);
  });
}

@reflectiveTest
class AvoidInlineQualifierTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = AvoidInlineQualifier();
    super.setUp();
  }

  Future<void> test_inlineQualifier() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

@module
class ConfigModule {
  @provides
  @Qualifier(#timeout)
  int provideTimeout() => 30;
}

class Client {
  @inject
  Client(@Qualifier(#timeout) this.timeout);
  final int timeout;
}
''',
    ['@Qualifier(#timeout)', '…@Qualifier(#timeout)'],
  );

  Future<void> test_qualifierConstant() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

const timeout = Qualifier(#timeout);

@module
class ConfigModule {
  @provides
  @timeout
  int provideTimeout() => 30;
}
''');

  Future<void> test_otherAnnotationWithArguments() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

@Component([])
abstract class MainComponent {}
''');
}
