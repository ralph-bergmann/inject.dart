import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../../data/repositories/counter_repository.dart';
import 'my_home_page.dart';

/// The view model for the [MyHomePage] widget.
@inject
class MyHomePageViewModel extends ChangeNotifier {
  MyHomePageViewModel({required CounterRepository repository}) : _repository = repository;

  final CounterRepository _repository;

  int count = 0;

  Future<void> increaseCount() async {
    await _repository.increaseCount();
    count = await _repository.count;
    notifyListeners();
  }
}
