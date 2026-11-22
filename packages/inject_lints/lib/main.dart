import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/fixes.dart';
import 'src/rules/avoid_asynchronous_on_inject.dart';
import 'src/rules/avoid_generated_component.dart';
import 'src/rules/avoid_inject_constructor_in_component.dart';
import 'src/rules/avoid_inline_qualifier.dart';
import 'src/rules/avoid_manual_view_model_builder.dart';
import 'src/rules/avoid_qualified_and_unqualified_provider.dart';
import 'src/rules/prefer_inject_over_provides.dart';
import 'src/rules/prefer_injected_widget.dart';
import 'src/rules/prefer_single_entry_point.dart';
import 'src/rules/require_abstract_component.dart';
import 'src/rules/require_assisted_parameter.dart';
import 'src/rules/require_provides_annotation.dart';
import 'src/rules/require_provision_listener_type.dart';
import 'src/rules/require_public_module.dart';
import 'src/rules/require_unambiguous_inject_constructor.dart';
import 'src/rules/require_valid_factory.dart';
import 'src/rules/require_valid_module_list.dart';

/// The analysis server looks up this variable to load the plugin.
final plugin = InjectLintsPlugin();

class InjectLintsPlugin extends Plugin {
  @override
  String get name => 'inject_lints';

  @override
  void register(PluginRegistry registry) {
    // Warning rules are on by default: they report code that inject.dart
    // rejects or ignores, so the problem shows before the build runs.
    registry
      ..registerWarningRule(RequireAbstractComponent())
      ..registerWarningRule(AvoidInjectConstructorInComponent())
      ..registerWarningRule(RequirePublicModule())
      ..registerWarningRule(RequireProvidesAnnotation())
      ..registerWarningRule(RequireValidModuleList())
      ..registerWarningRule(RequireProvisionListenerType())
      ..registerWarningRule(AvoidQualifiedAndUnqualifiedProvider())
      ..registerWarningRule(RequireUnambiguousInjectConstructor())
      ..registerWarningRule(AvoidAsynchronousOnInject())
      ..registerWarningRule(RequireAssistedParameter())
      ..registerWarningRule(RequireValidFactory());

    registry
      ..registerFixForRule(RequireAbstractComponent.code, AddAbstract.new)
      ..registerFixForRule(RequireValidFactory.code, AddAbstract.new)
      ..registerFixForRule(AvoidInjectConstructorInComponent.code, RemoveInjectAnnotation.new)
      ..registerFixForRule(RequireProvidesAnnotation.code, AddProvides.new)
      ..registerFixForRule(RequireValidModuleList.code, RemoveDuplicateEntry.new)
      ..registerFixForRule(AvoidAsynchronousOnInject.code, RemoveAsynchronous.new)
      ..registerFixForRule(RequireAssistedParameter.code, ReplaceWithInject.new);

    // Lint rules are off by default: they check style, so a project enables
    // each one it wants.
    registry
      ..registerLintRule(PreferSingleEntryPoint())
      ..registerLintRule(AvoidGeneratedComponent())
      ..registerLintRule(PreferInjectOverProvides())
      ..registerLintRule(PreferInjectedWidget())
      ..registerLintRule(AvoidInlineQualifier())
      ..registerLintRule(AvoidManualViewModelBuilder());
  }
}
