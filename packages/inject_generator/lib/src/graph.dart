// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library;

import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import 'context.dart';
import 'source/injected_type.dart';
import 'source/lookup_key.dart';
import 'source/symbol_path.dart';
import 'summary.dart';

part 'graph/component_graph.dart';
part 'graph/component_graph_resolver.dart';
part 'graph/summary_reader.dart';
