// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build/build.dart' as build show log;
import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';

/// Runs [fn] within a [Zone] with its own [BuilderContext].
Future<E> runInContext<E>(BuildStep buildStep, Future<E> Function() fn) {
  final completer = Completer<E>();

  Chain.capture(
    () => runZoned(
      () async {
        completer.complete(await fn());
      },
      zoneValues: {#builderContext: BuilderContext._(buildStep)},
    ),
    onError: (e, chain) {
      completer.completeError(e, chain.terse);
    },
  );

  return completer.future;
}

/// Currently active [BuilderContext].
BuilderContext get builderContext {
  final context = Zone.current[#builderContext];
  if (context == null) {
    throw StateError(
      'No current $BuilderContext is active. Start your build function using '
      '"runInContext" to be able to use "builderContext"',
    );
  }
  return context;
}

/// Contains services related to the currently executing [BuildStep].
class BuilderContext {
  const BuilderContext._(this.buildStep);

  /// The build step currently being processed.
  final BuildStep buildStep;

  /// The logger scoped to the current [buildStep] and therefore scoped to the
  /// currently processed input file.
  Logger get rawLogger => build.log;
}

String constructMessage(AssetId inputId, Element? element, String message) {
  ElementDeclarationResult? elementDeclaration;
  if (element != null && element.kind != ElementKind.DYNAMIC) {
    final parsedLibrary = element.library?.session.getParsedLibraryByElement(element.library!);
    if (parsedLibrary is ParsedLibraryResult) {
      elementDeclaration = parsedLibrary.getElementDeclaration(element);
    }
  }
  String? sourceLocation;
  String source;

  if (elementDeclaration == null || element?.source == null) {
    sourceLocation = 'at unknown source location';
    source = '.';
  } else {
    final offset = elementDeclaration.node.offset;
    sourceLocation = elementDeclaration.parsedUnit?.lineInfo.getLocation(offset).toString();
    final code = elementDeclaration.node.toSource();
    source = ':\n\n$code';
  }

  return '${inputId.uri} $sourceLocation: $message$source';
}
