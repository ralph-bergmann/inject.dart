// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library;

import 'package:inject_annotation/inject_annotation.dart';

import 'coffee_app.inject.dart' as g;
import 'src/coffee_maker.dart';
import 'src/drip_coffee_module.dart';
import 'src/thermosiphon.dart';

/// An example component class.
///
/// This component uses [DripCoffeeModule] as a source of dependency providers.
@Component(modules: [DripCoffeeModule])
abstract class Coffee {
  /// A generated `async` static function, which takes a [DripCoffeeModule] and
  /// asynchronously returns an instance of [Coffee].
  static const create = g.Coffee$Component.create;

  /// An accessor to an object that an application may use.
  @inject
  Future<CoffeeMaker> getCoffeeMaker();

  //TODO: why is this processed even when it isn't annotated?
  Provider<Future<Thermosiphon>> get thermosiphon;
}
