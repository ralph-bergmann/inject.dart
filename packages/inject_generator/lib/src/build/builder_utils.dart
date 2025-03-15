// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:build/build.dart';

// Strings must match build.yaml
const String summaryInputExtension = '.dart';
const String summaryOutputExtension = '.inject_summary.json';
const String componentOutputExtension = '.inject_component.json';
const String codegenOutputExtension = '.inject.dart';

extension BuilderExtensions on Builder {
  Future<void> saveContent(BuildStep buildStep, String oldExtension, String newExtension, String? content) async {
    final outputFile = buildStep.inputId.replaceExtension(oldExtension, newExtension);
    if (content != null && content.isNotEmpty) {
      await buildStep.writeAsString(outputFile, content);
    }
  }
}

extension AssetIdExtensions on AssetId {
  /// Returns a new [AssetId] with the same [package] but with [oldExtension]
  /// at the end of the path replaced by [newExtension].
  ///
  /// Only replaces the extension if it's at the end of the path string.
  /// Handles multi-part extensions in the format .xxx.yyy correctly.
  AssetId replaceExtension(String oldExtension, String newExtension) {
    final pathString = path;
    if (!pathString.endsWith(oldExtension)) {
      return this;
    }
    final newPath = pathString.substring(0, pathString.length - oldExtension.length) + newExtension;
    return AssetId(package, newPath);
  }
}
