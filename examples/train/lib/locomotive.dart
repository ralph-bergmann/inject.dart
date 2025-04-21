import 'package:inject_annotation/inject_annotation.dart';

import 'bike.dart';
import 'common.dart';
import 'food.dart';
import 'locomotive.inject.dart' as g;

/// The top level component that stitches together multiple app features into
/// a complete app.
@Component(modules: [BikeServices, FoodServices, CommonServices])
abstract class TrainServices implements BikeServiceLocator, FoodServiceLocator {
  static TrainServices create() {
    final services = g.TrainServices$Component.create();
    bikeServices = services;
    foodServices = services;
    return services;
  }
}
