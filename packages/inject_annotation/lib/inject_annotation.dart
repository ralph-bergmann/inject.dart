// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Annotations for the inject.dart dependency injection framework.
///
/// This package contains only the annotations and runtime contracts used to
/// declare the dependency graph. Add `inject_generator` as a `dev_dependency`
/// to generate the wiring from these annotations.
library;

export 'src/api/annotations.dart'
    show
        Assisted,
        AssistedFactory,
        AssistedInject,
        Asynchronous,
        Component,
        Inject,
        Module,
        Provides,
        ProvisionListenerAnnotation,
        Qualifier,
        Singleton,
        Subcomponent,
        SubcomponentFactory,
        assisted,
        assistedFactory,
        assistedInject,
        asynchronous,
        component,
        inject,
        module,
        provides,
        provisionListener,
        singleton,
        subcomponent,
        subcomponentFactory;
export 'src/api/provider.dart';
export 'src/api/provision_listener.dart';
