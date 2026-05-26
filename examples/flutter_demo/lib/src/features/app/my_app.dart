import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../home/home_page.dart';

part 'my_app.factory.dart';

/// Root widget of the application.
///
/// [@assistedInject] supplies [homePageFactory] from the DI graph at build
/// time; [key] is provided by the caller at runtime.
class MyApp extends StatelessWidget {
  @assistedInject
  const MyApp({@assisted super.key, required this.homePageFactory});

  final HomePageFactory homePageFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counter App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: homePageFactory.create(title: 'Flutter Counter Demo'),
    );
  }
}
