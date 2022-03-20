import 'package:flutter/material.dart';
import 'package:record/Recorder.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recorder App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const RecorderPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
