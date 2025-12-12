import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'frame4.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EVOBOT Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      debugShowCheckedModeBanner: false,
      home: const Frame4(),
    );
  }
}
