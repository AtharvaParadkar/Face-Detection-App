import 'package:flutter/material.dart';

import 'home_page.dart';

void main () {
  runApp(FaceDetection());
}

class FaceDetection extends StatelessWidget {
  const FaceDetection({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: .dark,
      home: HomePage(),
    );
  }
}
