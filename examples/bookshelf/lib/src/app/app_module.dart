import 'package:inject_annotation/inject_annotation.dart';

import '../session/session_component.dart';

/// Install point for the session subcomponent.
///
/// Listing [SessionComponent] here — not on `MainComponent` — is what makes
/// the session graph an encapsulated child: only this module (and whoever
/// consumes the generated `SessionComponentFactory`) needs to know it
/// exists. [AppModule] contributes no bindings of its own; installing a
/// subcomponent is a complete reason for a module to exist.
@Module(subcomponents: [SessionComponent])
class AppModule {}
