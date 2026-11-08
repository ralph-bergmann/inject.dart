import 'package:inject_annotation/inject_annotation.dart';

import 'typedef_provider_extra_param_shapes.inject.dart' as g;

part 'typedef_provider_extra_param_shapes.factory.dart';

// Every typedef here is unbound, so each one gets a synthesized provider. The
// extra constructor parameters cover nullable, repeated, mixed and qualified
// shapes. FirstTwin and SecondTwin share one signature and get one provider
// each. ChildMixedBuilder lives in the subcomponent and reads Clock through the
// parent, where Clock and Clock? stay two keys. RepeatedInjectable and
// RepeatedProvided show that the repeated shape also works outside typedefs.

const primary = Qualifier(#primary);
const secondary = Qualifier(#secondary);

typedef NullableBuilder = NullableBuilt Function(String name);
typedef RepeatedBuilder = RepeatedBuilt Function(String name);
typedef MixedBuilder = MixedBuilt Function(String name);
typedef QualifiedBuilder = QualifiedBuilt Function(String name);
typedef FirstTwin = Twin Function(String name);
typedef SecondTwin = Twin Function(String name);
typedef ChildMixedBuilder = ChildMixedBuilt Function(String name);
typedef AbstractFactoryBuilder = AbstractFactoryBuilt Function(String name);

class Clock {
  @inject
  const Clock();
}

// Nothing binds Missing, so discovering QClock.second would fail the build.
class Missing {}

class QClock {
  @inject
  @primary
  const QClock.first();

  @inject
  @secondary
  const QClock.second(Missing missing);
}

class NullableBuilt {
  const NullableBuilt(this.name, this.clock);

  final String name;
  final Clock? clock;
}

class RepeatedBuilt {
  const RepeatedBuilt(this.name, this.first, this.second);

  final String name;
  final Clock first;
  final Clock second;
}

class MixedBuilt {
  const MixedBuilt(this.name, this.first, this.second);

  final String name;
  final Clock first;
  final Clock? second;
}

class QualifiedBuilt {
  const QualifiedBuilt(this.name, @primary this.clock);

  final String name;
  final QClock clock;
}

class Twin {
  const Twin(this.name, this.clock);

  final String name;
  final Clock clock;
}

// Abstract, but its factory constructor can be called, so it keeps a provider.
abstract class AbstractFactoryBuilt {
  const factory AbstractFactoryBuilt(String name, Clock clock) = _AbstractFactoryBuiltImpl;
}

class _AbstractFactoryBuiltImpl implements AbstractFactoryBuilt {
  const _AbstractFactoryBuiltImpl(this.name, this.clock);

  final String name;
  final Clock clock;
}

class ChildMixedBuilt {
  const ChildMixedBuilt(this.name, this.first, this.second);

  final String name;
  final Clock first;
  final Clock? second;
}

class RepeatedInjectable {
  @inject
  const RepeatedInjectable(this.first, this.second);

  final Clock first;
  final Clock second;
}

class RepeatedProvided {
  const RepeatedProvided(this.first, this.second);

  final Clock first;
  final Clock second;
}

class Page {
  @assistedInject
  const Page(
    this.nullableBuilder,
    this.repeatedBuilder,
    this.mixedBuilder,
    this.qualifiedBuilder,
    this.firstTwin,
    this.secondTwin,
    this.abstractFactoryBuilder,
    @assisted this.title,
  );

  final NullableBuilder nullableBuilder;
  final RepeatedBuilder repeatedBuilder;
  final MixedBuilder mixedBuilder;
  final QualifiedBuilder qualifiedBuilder;
  final FirstTwin firstTwin;
  final SecondTwin secondTwin;
  final AbstractFactoryBuilder abstractFactoryBuilder;
  final String title;
}

class SessionView {
  @assistedInject
  const SessionView(this.builder, @assisted this.userId);

  final ChildMixedBuilder builder;
  final String userId;
}

@subcomponent
abstract class SessionSubcomponent {
  SessionViewFactory get sessionViewFactory;
}

@Module(subcomponents: [SessionSubcomponent])
class AppModule {
  @provides
  RepeatedProvided provideRepeated(Clock first, Clock second) => RepeatedProvided(first, second);
}

@Component([AppModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  PageFactory get pageFactory;

  RepeatedInjectable get repeatedInjectable;

  RepeatedProvided get repeatedProvided;

  SessionSubcomponentFactory get sessionFactory;
}
