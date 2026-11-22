import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';

/// Base class for the rule tests.
///
/// The tests run on an in-memory file system, so the real packages are not
/// available. This class adds stubs for `inject_annotation`, `inject_flutter`
/// and Flutter with just the declarations the rules look at.
abstract class InjectRuleTest extends AnalysisRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    newPackage('inject_annotation').addFile('lib/inject_annotation.dart', _injectAnnotation);
    newPackage('inject_flutter').addFile('lib/inject_flutter.dart', _injectFlutter);
    super.setUp();
  }

  /// Asserts that [code] gets this rule's diagnostic exactly on each of
  /// [texts], and no other diagnostic.
  ///
  /// Each text marks its first occurrence in [code]; start it with `…` to
  /// mark its last occurrence instead.
  Future<void> assertLints(String code, List<String> texts) => assertDiagnostics(code, [
    for (final String text in texts)
      if (text.startsWith('…'))
        lint(code.lastIndexOf(text.substring(1)), text.length - 1)
      else
        lint(code.indexOf(text), text.length),
  ]);

  /// Asserts that [code] gets this rule's diagnostic on [text], and that
  /// [fix] turns [code] into [expected].
  Future<void> assertFix(
    String code,
    String text,
    ResolvedCorrectionProducer Function({required CorrectionProducerContext context}) fix,
    String expected,
  ) async {
    await assertLints(code, [text]);
    final Diagnostic diagnostic = result.diagnostics.singleWhere((d) => d.diagnosticCode.lowerCaseName == rule.name);
    final library = await result.session.getResolvedLibrary(result.path) as ResolvedLibraryResult;
    final ResolvedCorrectionProducer producer = fix(
      context: CorrectionProducerContext.createResolved(
        libraryResult: library,
        unitResult: result,
        diagnostic: diagnostic,
        selectionOffset: diagnostic.offset,
        selectionLength: diagnostic.length,
      ),
    );
    final builder = ChangeBuilder(session: result.session);
    await producer.compute(builder);
    final List<SourceFileEdit> edits = builder.sourceChange.edits;
    expect(edits, hasLength(1), reason: 'The fix made no change.');
    expect(SourceEdit.applySequence(code, edits.single.edits), expected);
  }
}

const _injectAnnotation = r'''
class Component {
  const Component([this.modules = const []]);
  final List<Type> modules;
}

const component = Component();

class Subcomponent {
  const Subcomponent([this.modules = const []]);
  final List<Type> modules;
}

const subcomponent = Subcomponent();

class Module {
  const Module({this.subcomponents = const [], this.includes = const []});
  final List<Type> subcomponents;
  final List<Type> includes;
}

const module = Module();

class Inject {
  const Inject();
}

const inject = Inject();

class AssistedInject {
  const AssistedInject();
}

const assistedInject = AssistedInject();

class Assisted {
  const Assisted();
}

const assisted = Assisted();

class AssistedFactory {
  const AssistedFactory();
}

const assistedFactory = AssistedFactory();

class SubcomponentFactory {
  const SubcomponentFactory();
}

const subcomponentFactory = SubcomponentFactory();

class Provides {
  const Provides();
}

const provides = Provides();

class Singleton {
  const Singleton();
}

const singleton = Singleton();

class Asynchronous {
  const Asynchronous();
}

const asynchronous = Asynchronous();

class Qualifier {
  const Qualifier(this.name);
  final Symbol name;
}

abstract class Provider<T> {
  T get();
}

class ProvisionListenerAnnotation {
  const ProvisionListenerAnnotation();
}

const provisionListener = ProvisionListenerAnnotation();

abstract class ProvisionListener<T> {
  void onProvision(T instance);
}
''';

const _injectFlutter = r'''
import 'package:flutter/widgets.dart';

typedef ViewModelFactory<T extends Object> = ViewModelBuilder<T> Function({
  required Widget Function(BuildContext context, T viewModel) builder,
});

class ViewModelBuilder<T extends Object> extends StatefulWidget {
  const ViewModelBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, T viewModel) builder;

  @override
  State<ViewModelBuilder<T>> createState() => throw UnimplementedError();
}
''';
