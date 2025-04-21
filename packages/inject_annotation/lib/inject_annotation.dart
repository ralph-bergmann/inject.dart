// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A DI framework for Dart
library;

export 'src/api/annotations.dart'
    show
        Component,
        Provides,
        Qualifier,
        assisted,
        assistedFactory,
        assistedInject,
        asynchronous,
        component,
        inject,
        module,
        provides,
        singleton;
export 'src/api/provider.dart';
export 'src/api/provision_listener.dart';
