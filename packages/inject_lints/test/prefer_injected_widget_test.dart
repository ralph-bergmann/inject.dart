import 'package:inject_lints/src/rules/prefer_injected_widget.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferInjectedWidgetTest);
  });
}

@reflectiveTest
class PreferInjectedWidgetTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = PreferInjectedWidget();
    super.setUp();
  }

  Future<void> test_takesInjectedClass() => assertLints(
    r'''
import 'package:flutter/widgets.dart';
import 'package:inject_annotation/inject_annotation.dart';

@inject
class Repository {}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.repository});

  final Repository repository;

  @override
  Widget build(BuildContext context) => context.widget;
}
''',
    ['HomePage'],
  );

  Future<void> test_takesViewModelFactory() => assertLints(
    r'''
import 'package:flutter/widgets.dart';
import 'package:inject_flutter/inject_flutter.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.viewModelFactory});

  final ViewModelFactory<Object> viewModelFactory;

  @override
  Widget build(BuildContext context) => context.widget;
}
''',
    ['HomePage'],
  );

  Future<void> test_takesProvider() => assertLints(
    r'''
import 'package:flutter/widgets.dart';
import 'package:inject_annotation/inject_annotation.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.name});

  final Provider<String> name;

  @override
  Widget build(BuildContext context) => context.widget;
}
''',
    ['HomePage'],
  );

  Future<void> test_takesGeneratedFactory() => assertLints(
    r'''
import 'package:flutter/widgets.dart';
import 'package:inject_annotation/inject_annotation.dart';

class DetailPage extends StatelessWidget {
  @assistedInject
  const DetailPage({@assisted super.key});

  @override
  Widget build(BuildContext context) => context.widget;
}

abstract class DetailPageFactory {
  DetailPage create({Key? key});
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.detailPageFactory});

  final DetailPageFactory detailPageFactory;

  @override
  Widget build(BuildContext context) => detailPageFactory.create();
}
''',
    ['HomePage'],
  );

  Future<void> test_designSystemWidget() => assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';

typedef LabelBuilder = String Function(int count);

class Badge {
  const Badge(this.count);
  final int count;
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.badge,
    this.labelBuilder,
    this.child,
  });

  final String label;
  final void Function() onPressed;
  final Badge? badge;
  final LabelBuilder? labelBuilder;
  final Widget? child;

  @override
  Widget build(BuildContext context) => context.widget;
}
''');

  Future<void> test_injectedWidget() => assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:inject_annotation/inject_annotation.dart';

@inject
class Repository {}

class HomePage extends StatelessWidget {
  @assistedInject
  const HomePage({@assisted super.key, required this.repository});

  final Repository repository;

  @override
  Widget build(BuildContext context) => context.widget;
}
''');

  Future<void> test_privateWidget() => assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:inject_annotation/inject_annotation.dart';

@inject
class Repository {}

class _Header extends StatelessWidget {
  const _Header({required this.repository});

  final Repository repository;

  @override
  Widget build(BuildContext context) => context.widget;
}

Widget f(Repository repository) => _Header(repository: repository);
''');

  Future<void> test_classThatIsNoWidget() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

@inject
class Repository {}

class UseCase {
  UseCase(this.repository);
  final Repository repository;
}
''');
}
