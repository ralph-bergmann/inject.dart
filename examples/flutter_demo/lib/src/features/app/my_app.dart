import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../home/my_home_page.dart';

/// Factory to create the [MyApp] widget with the [MyHomePageFactory] injected.
@assistedFactory
abstract class MyAppFactory {
  MyApp create({Key? key});
}

/// The root widget of the application.
/// The [MyHomePageFactory] is injected into the widget at compile-time.
class MyApp extends StatelessWidget {
  @assistedInject
  const MyApp({
    @assisted super.key,
    required this.homePageFactory,
  });

  final MyHomePageFactory homePageFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: homePageFactory.create(title: 'Flutter Demo Home Page'),
    );
  }
}
